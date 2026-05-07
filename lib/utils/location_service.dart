import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:attendance_app/utils/app_session.dart';

/// Singleton service for managing location with caching
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // ── Fallback office location constants (used only before session loads) ──
  static const double _fallbackLat = 12.9571241;
  static const double _fallbackLng = 80.2452581;
  static const double _fallbackRadius = 500;

  /// Dynamic office latitude — reads from AppSession, falls back to constant.
  static double get officeLat =>
      AppSession().officeLat ?? _fallbackLat;

  /// Dynamic office longitude — reads from AppSession, falls back to constant.
  static double get officeLng =>
      AppSession().officeLng ?? _fallbackLng;

  /// Dynamic allowed radius in metres — reads from AppSession, falls back to constant.
  static double get allowedRadius =>
      AppSession().allowedRadius;

  /// Static wrapper for stream
  static Stream<LocationData> getStream() => _instance.locationStream;

  /// Static helper for reverse geocoding
  static Future<String?> getAddress(double lat, double lng) async {
    try {
      if (!kIsWeb) {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          return "${place.street}, ${place.subLocality}, ${place.locality} - ${place.postalCode}";
        }
      }
    } catch (e) {
      print("⚠️ Static getAddress failed: $e");
    }
    return null;
  }

  // Cache configuration
  static const Duration _cacheExpiry = Duration(seconds: 30);
  static const Duration _locationTimeout = Duration(seconds: 20);

  /// Max acceptable accuracy in meters. Positions worse than this (higher number) are rejected.
  static const double _maxAcceptableAccuracy = 100.0;

  // Cached data
  Position? _cachedPosition;
  DateTime? _lastFetchTime;
  String? _cachedDistanceInfo;
  String? _cachedAddress;

  // Stream controller for reactive updates
  final _locationController = StreamController<LocationData>.broadcast();
  Stream<LocationData> get locationStream => _locationController.stream;

  StreamSubscription<Position>? _positionStreamSubscription;
  DateTime? _lastAddressFetchTime;
  bool _isTracking = false;

  bool _isFetching = false;
  bool _isInitialized = false;

  /// Initialize location service (Request permissions once)
  Future<void> initialize() async {
    // If we're already initialized and have no error, skip
    if (_isInitialized && _locationController.hasListener) {
      // Check if we actually have permission though, just in case revoked
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.always ||
          p == LocationPermission.whileInUse) {
        return;
      }
    }

    print("📍 Initializing Location Service...");
    _isInitialized = true; // Mark as initialized to prevent concurrent calls

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _emitError(
          "Location services are disabled", "Please enable location services");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _emitError("Location permission denied", "Permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _emitError("Location permission permanently denied",
          "Permission permanently denied");
      return;
    }

    _isInitialized = true;
    print("✅ Location Service Initialized");
  }

  // No changes needed here, just context for previous replace
  /// Get current location with caching
  Future<LocationData> getLocation({bool forceRefresh = false}) async {
    // Ensure initialized
    if (!_isInitialized) await initialize();

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid()) {
      return LocationData(
        position: _cachedPosition,
        distanceInfo: _cachedDistanceInfo!,
        address: _cachedAddress,
        isLoading: false,
        error: null,
      );
    }

    // Prevent concurrent fetches (but allow forceRefresh to wait)
    if (_isFetching) {
      if (forceRefresh) {
        // Wait for ongoing fetch to complete, then retry
        print("⏳ Refresh requested but fetch in progress. Waiting...");
        await Future.delayed(const Duration(milliseconds: 500));
        return getLocation(forceRefresh: true); // Retry
      } else {
        // Return cached data if available
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isCacheValid()) {
          return LocationData(
            position: _cachedPosition,
            distanceInfo: _cachedDistanceInfo!,
            address: _cachedAddress,
            isLoading: false,
            error: null,
          );
        }
      }
    }

    _isFetching = true;

    // Emit Loading State immediately
    _locationController.add(LocationData(
      position: _cachedPosition, // Keep showing old position while loading
      distanceInfo: "Updating...",
      address: _cachedAddress,
      isLoading: true,
      error: null,
    ));

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final error = LocationData(
          position: null,
          distanceInfo: "Location Disabled",
          address: null,
          isLoading: false,
          error: "Please enable location services",
        );
        _locationController.add(error);
        return error;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          final error = LocationData(
            position: null,
            distanceInfo: "Permission Denied",
            address: null,
            isLoading: false,
            error: "Location permission denied",
          );
          _locationController.add(error);
          return error;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        final error = LocationData(
          position: null,
          distanceInfo: "Permission Denied Forever",
          address: null,
          isLoading: false,
          error: "Location permission permanently denied",
        );
        _locationController.add(error);
        return error;
      }

      // Strategy: Try last known position first (instant, no timeout), then current position
      Position? position;

      // 1️⃣ Try to get last known position first (much faster)
      // BUT: Only use if it's recent (< 30 seconds old) AND accurate enough
      if (!kIsWeb) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            final now = DateTime.now();
            final difference = now.difference(lastKnown.timestamp);
            final isRecent = difference.inSeconds < 30;
            final isAccurate = lastKnown.accuracy <= _maxAcceptableAccuracy;

            if (isRecent && isAccurate) {
              print(
                  "📍 Using fresh+accurate last known position (${difference.inSeconds}s old, ±${lastKnown.accuracy.toInt()}m)");
              position = lastKnown;
            } else {
              print(
                  "⚠️ Last known position rejected: age=${difference.inSeconds}s, accuracy=±${lastKnown.accuracy.toInt()}m (threshold: ${_maxAcceptableAccuracy.toInt()}m). Fetching fresh.");
            }
          }
        } catch (e) {
          print("⚠️ No last known position available: $e");
        }
      }

      // 2️⃣ If no accurate last known position, fetch current position
      if (position == null) {
        try {
          print("📍 Fetching current position with HIGH accuracy...");
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: _locationTimeout,
          );
          print(
              "✅ Got current position: ${position.latitude}, ${position.longitude} ±${position.accuracy.toInt()}m");

          // 3️⃣ If accuracy is poor, wait briefly to get a better GPS fix
          if (position.accuracy > _maxAcceptableAccuracy) {
            print(
                "⚠️ Accuracy poor (±${position.accuracy.toInt()}m). Waiting for a better fix...");
            await Future.delayed(const Duration(seconds: 3));
            try {
              final betterPosition = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 10),
              );
              if (betterPosition.accuracy < position.accuracy) {
                print(
                    "✅ Got a better position: ±${betterPosition.accuracy.toInt()}m (was ±${position.accuracy.toInt()}m)");
                position = betterPosition;
              }
            } catch (_) {
              print("⚠️ Second attempt failed. Using first position.");
            }
          }
        } catch (e) {
          print("❌ Current position failed: $e");

          // 4️⃣ If timeout, try one more time with MEDIUM accuracy
          if (e.toString().toLowerCase().contains("timeout")) {
            print(
                "📍 Timeout on high accuracy. Retrying with MEDIUM accuracy...");
            try {
              position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
                timeLimit: const Duration(seconds: 10),
              );
              print(
                  "✅ Got position on retry: ${position.latitude}, ${position.longitude} ±${position.accuracy.toInt()}m");
            } catch (retryError) {
              print("❌ Retry also failed: $retryError");
              throw e;
            }
          } else {
            throw e;
          }
        }
      }

      // If still no position, throw error
      if (position == null) {
        throw Exception("Unable to get location after all attempts");
      }

      // Calculate distance from office
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );

      // Fetch Address (Best Effort)
      String? address;
      try {
        if (!kIsWeb) {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;
            address =
                "${place.street}, ${place.subLocality}, ${place.locality} - ${place.postalCode}";
          }
        }
      } catch (e) {
        print("⚠️ Address fetch failed: $e");
      }

      // Update cache
      _cachedPosition = position;
      _lastFetchTime = DateTime.now();
      final accuracyLabel = position.accuracy <= 50
          ? "GPS"
          : position.accuracy <= 100
              ? "~GPS"
              : "Low Accuracy";
      _cachedDistanceInfo =
          "${distance.toInt()}m from Office ($accuracyLabel ±${position.accuracy.toInt()}m)";
      _cachedAddress = address;

      final result = LocationData(
        position: position,
        distanceInfo: _cachedDistanceInfo!,
        address: _cachedAddress,
        isLoading: false,
        error: null,
      );

      // Notify listeners
      _locationController.add(result);

      return result;
    } catch (e) {
      print("❌ Location error: $e");

      // 4️⃣ Best Effort Fallback: If we have ANY cached position, use it even if expired
      if (_cachedPosition != null) {
        print("⚠️ Fetch failed, using expired cache as best-effort fallback.");
        final fallback = LocationData(
          position: _cachedPosition,
          distanceInfo: "${_cachedDistanceInfo} (Old)",
          address: _cachedAddress,
          isLoading: false,
          error: "Using old location (refresh failed)",
        );
        _locationController.add(fallback);
        return fallback;
      }

      String errorMsg = "Location unavailable";
      if (e.toString().toLowerCase().contains("timeout")) {
        errorMsg = "Location timeout - poor signal?";
      } else if (e.toString().toLowerCase().contains("permission")) {
        errorMsg = "Location permission needed";
      }

      final error = LocationData(
        position: null,
        distanceInfo: errorMsg,
        address: null,
        isLoading: false,
        error: e.toString(),
      );

      _locationController.add(error);
      return error;
    } finally {
      _isFetching = false;
    }
  }

  /// Start realtime location tracking
  Future<void> startRealtimeTracking() async {
    if (_isTracking) return;

    // Ensure initialized
    if (!_isInitialized) await initialize();

    // Double check permissions (safe)
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _emitError(
          "Location services are disabled", "Please enable location services");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _emitError("Location permission denied", "Permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _emitError("Location permission permanently denied",
          "Permission permanently denied");
      return;
    }

    _isTracking = true;
    print("📍 Starting realtime location tracking...");

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    try {
      _positionStreamSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) {
        _handlePositionUpdate(position);
      }, onError: (e) {
        print("❌ Realtime tracking error: $e");
        _emitError("Location error", e.toString());
        _isTracking = false;
      });
    } catch (e) {
      print("❌ Failed to start location stream: $e");
      _emitError("Failed to start tracking", e.toString());
      _isTracking = false;
    }
  }

  void _emitError(String distanceInfo, String errorMsg) {
    _locationController.add(LocationData(
      position: null,
      distanceInfo: distanceInfo,
      address: null,
      isLoading: false,
      error: errorMsg,
    ));
  }

  /// Stop realtime location tracking
  void stopRealtimeTracking() {
    _isTracking = false;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    print("📍 Stopped realtime location tracking");
  }

  /// Handle incoming position updates
  Future<void> _handlePositionUpdate(Position position) async {
    // Calculate distance
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      officeLat,
      officeLng,
    );

    // Throttled Address Fetching (every 30 seconds or if moved significantly)
    String? address = _cachedAddress;
    bool shouldFetchAddress = _cachedAddress == null;

    if (_lastAddressFetchTime != null) {
      final timeDiff = DateTime.now().difference(_lastAddressFetchTime!);
      if (timeDiff.inSeconds > 30) {
        shouldFetchAddress = true;
      }
    } else {
      shouldFetchAddress = true;
    }

    if (shouldFetchAddress && !kIsWeb) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          address =
              "${place.street}, ${place.subLocality}, ${place.locality} - ${place.postalCode}";
          _lastAddressFetchTime = DateTime.now();
        }
      } catch (e) {
        print("⚠️ Realtime address fetch failed: $e");
      }
    }

    // Update cache
    _cachedPosition = position;
    _lastFetchTime = DateTime.now();
    _cachedDistanceInfo = "${distance.toInt()}m from Office";
    _cachedAddress = address;

    // Emit update
    _locationController.add(LocationData(
      position: position,
      distanceInfo: _cachedDistanceInfo!,
      address: address,
      isLoading: false,
      error: null,
    ));
  }

  /// Check if user is within office location
  Future<bool> isWithinOfficeLocation() async {
    try {
      final locationData = await getLocation();

      if (locationData.position == null) {
        return false;
      }

      final distance = Geolocator.distanceBetween(
        locationData.position!.latitude,
        locationData.position!.longitude,
        officeLat,
        officeLng,
      );

      return distance <= allowedRadius;
    } catch (e) {
      print("⚠️ Office location check failed: $e");
      return false;
    }
  }

  /// Get LatLng from cached position
  LatLng? getLatLng() {
    if (_cachedPosition == null) return null;
    return LatLng(_cachedPosition!.latitude, _cachedPosition!.longitude);
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_cachedPosition == null ||
        _lastFetchTime == null ||
        _cachedDistanceInfo == null) {
      return false;
    }

    final now = DateTime.now();
    final difference = now.difference(_lastFetchTime!);
    return difference < _cacheExpiry;
  }

  /// Clear cache (useful for testing or forcing refresh)
  void clearCache() {
    _cachedPosition = null;
    _lastFetchTime = null;
    _cachedDistanceInfo = null;
    _cachedAddress = null;
  }

  /// Open app settings
  Future<bool> openSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings (to enable GPS)
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Dispose resources
  void dispose() {
    stopRealtimeTracking();
    _locationController.close();
  }
}

/// Data class for location information
class LocationData {
  final Position? position;
  final String distanceInfo;
  final String? address;
  final bool isLoading;
  final String? error;

  LocationData({
    required this.position,
    required this.distanceInfo,
    this.address,
    required this.isLoading,
    required this.error,
  });

  LatLng? get latLng {
    if (position == null) return null;
    return LatLng(position!.latitude, position!.longitude);
  }

  bool get isWithinRadius {
    if (position == null) return false;
    double distance = Geolocator.distanceBetween(
      position!.latitude,
      position!.longitude,
      LocationService.officeLat,
      LocationService.officeLng,
    );
    return distance <= LocationService.allowedRadius;
  }
}
